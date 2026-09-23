# Destinations and Mapping Specification

## Purpose

The user's Ninox database is theirs and the app has no rights over its shape. It may
not create fields, rename columns or assume anything exists, so everything the app is
allowed to write has to be stated by the user, field by field, and stored in a form
that survives the user reorganising their own database.

That turns three details into requirements rather than conveniences.

A destination that stored field **names** would break silently the first time a column
was renamed, because the app would write to a field that no longer exists. Identifiers
are stable and names are not.

A **formula field** cannot be written to at all — the API answers HTTP 500 — so it must
never be offered as a mapping candidate. But where that formula computes a total,
reading it back after a send is the app's only independent sight of what the user's own
table made of the values it received, and its blind spot has to be stated rather than
discovered.

And a value the document **does not print** has to become either an empty field or a
zero depending on what that column means to the user. That is a property of their
table, not of the document, and it is the one place in the product where the honest
answer is a per-field setting instead of a rule.

---

## ADDED Requirements

---

### Requirement: what-a-destination-is

A destination SHALL be the tuple of Ninox team, database, table, field mapping and
Ninox host, and the user SHALL be able to hold several destinations at once.
[Origen: Funcional §4.5 FR-DST-001; PDR §7.3; ADR-017]

#### Scenario: two destinations on the same database coexist

- GIVEN two destinations pointing at different tables of the same database
- WHEN the destination bar is used
- THEN both exist and the bar switches between them

#### Scenario: the host is part of the destination

- GIVEN two destinations on different Ninox hosts
- WHEN either is selected
- THEN the host travels with the destination rather than being global

---

### Requirement: no-default-destination-until-a-first-send

There SHALL be no built-in default destination when the app is first configured, and
once at least one send has happened the destination bar SHALL always show the
destination used last.
[Origen: Funcional §4.5 FR-DST-002; PDR §7.2, §7.3; Finding 4]

#### Scenario: a fresh installation has nothing pre-loaded

- GIVEN a fresh installation
- WHEN the review screen is opened
- THEN the destination is empty and requires the wizard

#### Scenario: after the first send the last destination is shown

- GIVEN at least one completed send
- WHEN the next capture is opened
- THEN the bar is pre-loaded with the destination used last
- AND the daily confirmation is the only acknowledgement required

---

### Requirement: destinations-store-identifiers-not-names

A destination SHALL store Ninox field **identifiers** and never field names, and the
current name SHALL be resolved at send time from a schema cached when the app opens,
while the payload itself is keyed by field name.
[Origen: Funcional §4.5 FR-DST-003; PDR §7.3; ADR-004; Annex A (names versus identifiers)]

#### Scenario: renaming a column does not break the destination

- GIVEN a destination mapped to a column the user then renames in Ninox
- WHEN the next send runs
- THEN the new name is resolved and the same column is written

#### Scenario: a destination stored by name fails this criterion

- GIVEN a destination that stored field names instead of identifiers
- WHEN the column is renamed
- THEN the write breaks or resolves incorrectly
- AND that implementation does not satisfy this requirement

---

### Requirement: formula-and-read-only-fields-are-not-mapping-candidates

Fields the schema marks as formula or read-only SHALL be excluded from the mapping
candidates offered to the user.
[Origen: Funcional §4.5 FR-DST-004; PDR §7.4, §8.1; ADR-004; Annex A (formula and read-only fields)]

#### Scenario: a formula field is not offered

- GIVEN a table whose total is a formula field
- WHEN the mapping picker is shown
- THEN that field does not appear among the candidates

#### Scenario: the app never provokes a 500 on a formula write

- GIVEN any destination the user can configure
- WHEN a record is written
- THEN no request targets a formula or read-only field
- AND the HTTP 500 the API returns for such a write is never produced

---

### Requirement: formula-totals-used-as-post-write-contrast

Where the destination table holds a formula field computing a total from mapped components, the app SHALL NOT write to it, and after a successful send SHALL read it back and compare it against the total extracted from the document, surfacing any mismatch to the user as a question about the mapping or the formula rather than as a verdict on the extraction.
[Origen: Funcional §4.5 FR-DST-005; PDR §7.4; 16-document test (the `YB` total is a formula field)]

#### Scenario: a mis-wired mapping is surfaced

- GIVEN a table whose formula is `base + tax` where base and tax were mapped to the wrong columns
- WHEN the record is read back
- THEN the mismatch is surfaced to the user
- AND the message names the mapping or the formula as the suspect, not the extraction

#### Scenario: the documented blind spot is honoured

- GIVEN a total that was misread and then used to derive its own components
- WHEN the formula contrast runs
- THEN the formula reproduces the error and the contrast passes
- AND the requirement is not treated as protection against that case

#### Scenario: the user is asked, not told

- GIVEN a mismatch between the read-back formula value and the extracted total
- WHEN it is presented
- THEN it is presented as a question about the mapping or the formula
- AND it is not presented as a failed extraction

---

### Requirement: per-field-absent-setting

Each mapped field SHALL carry one additional setting for what to write when the source
value is absent from the document: leave the Ninox field empty, which SHALL be the
default, or write zero. The setting SHALL be a property of the destination field and
not of the canonical model.
[Origen: Funcional §4.5 FR-DST-006; PDR §7.3; 16-document test, record 1414]

#### Scenario: the setting decides the written value

- GIVEN a card-terminal slip with no printed VAT
- WHEN the record is written
- THEN the VAT column receives empty or zero strictly according to that field's setting

#### Scenario: two destinations yield two different values for the same document

- GIVEN the same document and two destinations whose VAT fields have different settings
- WHEN it is sent to each
- THEN each receives the value its own setting dictates

#### Scenario: the default is empty

- GIVEN a mapped field with no setting made
- WHEN the source value is absent
- THEN the field is left empty
- AND zero is not written

---

### Requirement: choice-fields-offer-the-existing-options

For a Ninox choice field the mapping SHALL offer the field's existing options rather
than free text, and the value written SHALL be one of those options.
[Origen: Funcional §4.5 FR-DST-007; ADR-004; Annex A (choice fields)]

#### Scenario: the picker shows the field's own options

- GIVEN a choice field mapped to `doc_subtype`
- WHEN the mapping is configured
- THEN the field's existing options are offered
- AND free text is not accepted

#### Scenario: the written value belongs to the option list

- GIVEN a choice field with options in Ninox
- WHEN a record is written into it
- THEN the written value is one of them
- AND the text of the option is what a read returns

---

### Requirement: configurable-ninox-host

The Ninox host SHALL be a field in the destination's advanced setup, SHALL default to
`api.ninox.com`, SHALL be editable, SHALL never be compiled into the client's base URL
as a constant, and SHALL be validated at the token step exactly as the token is.
[Origen: Funcional §4.5 FR-DST-008; ADR-017; Finding 14]

#### Scenario: a private-cloud customer needs no fork

- GIVEN a customer running Ninox on their own host
- WHEN they configure the app
- THEN they enter their host and the app talks to it
- AND no fork and no manual build is required

#### Scenario: an unreachable host is reported early

- GIVEN an unreachable or invalid host
- WHEN the token step runs
- THEN the problem is reported there
- AND it is not deferred to the first send

---

### Requirement: never-write-an-unmapped-field

The app SHALL never write a Ninox field the user has not explicitly mapped, with the
consequence that no marker field may be relied upon to exist.
[Origen: Funcional §4.5 FR-DST-009; Funcional §5 BR-15; Funcional §2.4 contract line 6; ADR-013; PDR §8.2]

#### Scenario: no mapping means no field keys

- GIVEN a destination with no field mapped
- WHEN a record is sent
- THEN the payload contains no field keys at all
- AND the record carries only the attachment

#### Scenario: duplicate prevention cannot rely on a marker

- GIVEN the prohibition above
- WHEN duplicate prevention is designed
- THEN it is handled read-side against local history
- AND no marker field is assumed to exist in the user's table

---

## Out of Scope

- **Writing anything.** The payload shape, the attachment upload, the retry matrix,
  the reconciliation of an uncertain create, the deep link and the read-back are
  `ninox-send`'s, together with Annex A's write-path rows: payload shape, create
  response, merges, dates, error shape, retry policy, read-after-create and
  attachment upload.
- **Producing a destination.** The wizard, its five screens, the auto-omitted steps,
  the two-stage matching, the pre-filled proposals, the plain-language summary and the
  permission that nothing need be mapped are `setup-wizard`'s. This capability defines
  what a destination is and the rules its fields obey; the wizard applies them.
- **The principle behind the absent setting.** That a value not printed is not a zero,
  and that the destination decides, is `validation-confidence`'s (FR-VAL-012, BR-13).
  This capability owns the per-field setting that implements it.
- **The duplicate criteria.** `document-history` owns them, read-side, precisely
  because `never-write-an-unmapped-field` forbids relying on a marker field.
- **The confidence of a value.** `validation-confidence` owns it. This capability
  decides what is written, never how sure the app is.
- **Resolving a choice field written with text outside its option list.** It is
  unverified and open as **GAP-005**; this capability contains the risk by offering
  only existing options and does not claim to close it.

---

## Cross-Capability References

- `ninox-send` — performs the write this capability's destination describes, and owns
  Annex A's write-path rows. The split between the two capabilities' halves of Annex A
  is recorded in `openspec/project.md` §3.1.
- `setup-wizard` — produces destinations and must apply
  `formula-and-read-only-fields-are-not-mapping-candidates` and
  `choice-fields-offer-the-existing-options` rather than redefining them, and must
  respect that no mapping is mandatory.
- `validation-confidence` — owns the principle (FR-VAL-012, BR-13) that
  `per-field-absent-setting` implements, and owns the confidence state of every value
  this capability decides to write.
- `document-history` — owns the duplicate criteria, which live read-side because
  `never-write-an-unmapped-field` forbids a marker field.
- `product-invariants` — owns BR-16, never touch schema or records the app did not
  create, and BR-19, the token as the only credential, both of which bound what a
  destination may do.
- `extraction-pipeline` — owns the total that `formula-totals-used-as-post-write-contrast`
  compares against, and the read-before-derive rule that is the real protection against
  the case the contrast misses.

---

## Open Questions

- **GAP-005** — a choice field written with text that matches none of its options is
  unverified in every test so far. `choice-fields-offer-the-existing-options` offers
  only existing options, which contains the risk rather than eliminating it, and the
  requirement is written to be safe if the residual case behaves differently.
- **GAP-006** — the private-cloud host has not been re-verified against a private
  instance, so `configurable-ninox-host` cannot be considered closed for that segment.
  The behaviour is specified and testable; that particular verification is not done.
- **GAP-009** — the formula contrast's blind spot, recorded against
  `formula-totals-used-as-post-write-contrast` in the requirement itself so that a
  later reader cannot overvalue the check. The protection against a misread total used
  to derive its own components lives in `extraction-pipeline`, not here.
- **GAP-004** — the attachment-upload limits, including the maximum file size, are
  still open and concern `ninox-send`'s attachment step rather than anything here.
- **Settled before writing.** Annex A is a single annex whose rows act in two
  capabilities. Rather than leave it ambiguous, its rows are assigned explicitly:
  names versus identifiers, choice fields and formula or read-only fields are this
  capability's; payload shape, create response, merges, dates, error shape, retry
  policy, read-after-create and attachment upload are `ninox-send`'s.
